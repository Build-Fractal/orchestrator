#!/usr/bin/env bash
# Verifies runtime adapters are registered purely by filename — no central
# registry file lists them (mirrors P02 backend-registry pattern).
set -u

dir="scripts/dispatch/adapters/runtime"
if [[ ! -d "$dir" ]]; then
  echo "FAIL: $dir missing"
  exit 1
fi

expected=("claude-code.sh" "codex.sh" "cursor.sh")
for f in "${expected[@]}"; do
  if [[ ! -f "$dir/$f" ]]; then
    echo "FAIL: $dir/$f missing"
    exit 1
  fi
done

# Ensure no stray central-registry file exists.
forbidden=("runtime-registry.yml" "runtime-registry.yaml" "runtime-list.json" "runtimes.conf")
for name in "${forbidden[@]}"; do
  if find scripts -type f -name "$name" 2>/dev/null | grep -q .; then
    echo "FAIL: central registry file '$name' found (registration must be filename-based)"
    exit 1
  fi
done

echo "PASS: runtime adapter discovery is filename-based (3 adapters, no central registry)"
