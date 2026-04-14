#!/usr/bin/env bash
# Verifies backend-registry.sh discovers and probes adapters correctly.
set -u

f="scripts/dispatch/backend-registry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Script documents its contract
grep -q 'backends_discovered' "$f" || { echo "FAIL: $f missing backends_discovered key"; exit 1; }
grep -q 'backends_available' "$f" || { echo "FAIL: $f missing backends_available key"; exit 1; }
grep -q 'default_backend' "$f" || { echo "FAIL: $f missing default_backend key"; exit 1; }
grep -q '\-\-probe' "$f" || { echo "FAIL: $f does not probe adapters"; exit 1; }
grep -q 'adapters/backend' "$f" || { echo "FAIL: $f does not reference adapters directory"; exit 1; }

# Script must be bash 3.2 compatible (no declare -A)
if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$f"; then
  echo "FAIL: $f uses declare -A (not Bash 3.2 compatible)"; exit 1
fi

# Run the script in summary mode — must emit all three required keys and exit 0
output="$(bash "$f" 2>/dev/null)"
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "FAIL: $f exited $rc (expected 0)"; exit 1
fi
echo "$output" | grep -qE '^backends_discovered=' || { echo "FAIL: output missing backends_discovered"; exit 1; }
echo "$output" | grep -qE '^backends_available=' || { echo "FAIL: output missing backends_available"; exit 1; }
echo "$output" | grep -qE '^default_backend=' || { echo "FAIL: output missing default_backend"; exit 1; }

# --list mode must work without adapters present (may print nothing or list names)
bash "$f" --list >/dev/null 2>&1 || { echo "FAIL: --list mode failed"; exit 1; }

echo "PASS: backend-registry.sh discovers and probes adapters"
