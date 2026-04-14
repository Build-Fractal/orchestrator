#!/usr/bin/env bash
# m008-p04-bash32-compat.sh -- all P04 scripts are Bash 3.2 compatible
set -u

P04_SCRIPTS=(
  "scripts/state/resolve-root.sh"
  "scripts/state/detect-speckit.sh"
  "scripts/state/config-system.sh"
  "scripts/migrate/migrate-state.sh"
  "scripts/state/namespace-aliases.sh"
  "scripts/state/derive-phase.sh"
)

# Forbidden Bash 4+ idioms as extended-regex patterns.
FORBIDDEN_PATTERNS=(
  'declare[[:space:]]+-A'
  '(^|[^a-zA-Z])mapfile([^a-zA-Z]|$)'
  '(^|[^a-zA-Z])readarray([^a-zA-Z]|$)'
  '\[\[[[:space:]]+-v[[:space:]]'
  '\$\{[^}]*@[QULK][^}]*\}'
)

fail=0
for script in "${P04_SCRIPTS[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "FAIL: $script missing"
    fail=1
    continue
  fi
  for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    hit="$(grep -nE "$pat" "$script" || true)"
    if [[ -n "$hit" ]]; then
      echo "FAIL: $script contains Bash 4+ idiom matching /$pat/:"
      echo "$hit"
      fail=1
    fi
  done
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "PASS: no Bash 4+ idioms detected in P04 scripts"
exit 0
