#!/usr/bin/env bash
# scripts/diagnostics/check-providers.sh — Provider convention conformance check.
#
# Scans provider scripts (scripts/providers/*.sh by default) for required
# structural elements defined in references/provider-convention.md.
#
# Usage: check-providers.sh [--root <project-root>]
#
# Output: DOCTOR:PROVIDERS status=<ok|warn|skip> files=N issues=N
#
# Bash 3.2 compatible. AD-6 conformance.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "check-providers.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

PROVIDERS_DIR="$PROJECT_ROOT/scripts/providers"

# --- No providers directory: skip ---
if [ ! -d "$PROVIDERS_DIR" ]; then
  printf 'DOCTOR:PROVIDERS status=skip files=0 issues=0 reason=no_providers_dir\n'
  exit 0
fi

# --- Collect provider scripts ---
FILES=""
for f in "$PROVIDERS_DIR"/*.sh; do
  [ -f "$f" ] || continue
  FILES="${FILES}${f}
"
done

if [ -z "$FILES" ]; then
  printf 'DOCTOR:PROVIDERS status=skip files=0 issues=0 reason=no_provider_scripts\n'
  exit 0
fi

total_files=0
total_issues=0
details=""

# --- Required checks per provider script ---
# Each check greps for a pattern; absence is an issue.
while IFS= read -r file; do
  [ -z "$file" ] && continue
  total_files=$((total_files + 1))
  file_issues=0
  bname="$(basename "$file")"

  # 1. Bash shebang
  head_line="$(head -1 "$file")"
  case "$head_line" in
    '#!/usr/bin/env bash'|'#!/bin/bash') ;;
    *)
      file_issues=$((file_issues + 1))
      details="${details}  ISSUE: ${bname} — missing bash shebang
"
      ;;
  esac

  # 2. Error mode (set -eu or set -euo pipefail)
  if ! grep -qE '^set -e' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing set -e error mode
"
  fi

  # 3. --task argument parsing
  if ! grep -q '\-\-task' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing --task argument handling
"
  fi

  # 4. --phase argument parsing
  if ! grep -q '\-\-phase' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing --phase argument handling
"
  fi

  # 5. --output argument parsing
  if ! grep -q '\-\-output' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing --output argument handling
"
  fi

  # 6. emit_result call
  if ! grep -q 'emit_result' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — missing emit_result call
"
  fi

  # 7. errors.sh sourcing
  if ! grep -q 'errors\.sh' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — does not source errors.sh
"
  fi

  # 8. events.sh sourcing
  if ! grep -q 'events\.sh' "$file"; then
    file_issues=$((file_issues + 1))
    details="${details}  ISSUE: ${bname} — does not source events.sh
"
  fi

  total_issues=$((total_issues + file_issues))
done <<FILES_EOF
$FILES
FILES_EOF

# --- Emit structured result ---
if [ "$total_issues" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:PROVIDERS status=%s files=%d issues=%d\n' "$status" "$total_files" "$total_issues"
if [ -n "$details" ]; then
  printf '%s' "$details"
fi
