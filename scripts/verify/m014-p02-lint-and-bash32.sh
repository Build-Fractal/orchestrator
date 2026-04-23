#!/usr/bin/env bash
# Gate: every P02-modified/created shell script passes anti-pattern-lint
# and is Bash 3.2 compatible (no forbidden tokens).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/verify/anti-pattern-lint.sh"

if [ ! -x "$LINT" ]; then
  echo "FAIL: anti-pattern-lint.sh missing or not executable" >&2; exit 1
fi

# P02-touched files.
FILES="scripts/lifecycle/init-project.sh
scripts/lifecycle/reinit-handler.sh
scripts/knowledge/consolidate-artifacts.sh
scripts/diagnostics/check-docs.sh
scripts/diagnostics/run-doctor.sh
scripts/migrate/m014-p02-migrate-recent-changes.sh
scripts/verify/m014-p02-write-site-manifest.sh
scripts/verify/m014-p02-init-dual-write.sh
scripts/verify/m014-p02-reinit-dual-write.sh
scripts/verify/m014-p02-consolidate-dual-write.sh
scripts/verify/m014-p02-check-docs-drift.sh
scripts/verify/m014-p02-run-doctor-drift-section.sh
scripts/verify/m014-p02-doctor-md.sh
scripts/verify/m014-p02-migration-idempotent.sh
scripts/verify/m014-p02-lint-and-bash32.sh
scripts/verify/m014-p02-phase-suite.sh"

failed=0

# --- Anti-pattern lint pass ---
for f in $FILES; do
  path="$PROJECT_ROOT/$f"
  if [ ! -f "$path" ]; then
    echo "FAIL: missing file: $f" >&2
    failed=$((failed + 1))
    continue
  fi
  if ! bash "$LINT" --fixture "$path" >/dev/null 2>&1; then
    echo "FAIL: anti-pattern-lint rejected: $f" >&2
    failed=$((failed + 1))
  fi
done

# --- Bash 3.2 compat scan ---
# Forbidden tokens: declare -A, mapfile, ${var,,}, ${var^^}, <(...), &>.
# We scan each file; the scanner itself self-excludes (diagnostic strings match).
SELF="$(basename "${BASH_SOURCE[0]}")"

for f in $FILES; do
  # Skip self (diagnostic strings contain the forbidden tokens as literals).
  bname="$(basename "$f")"
  if [ "$bname" = "$SELF" ]; then continue; fi

  # Also skip anti-pattern-lint.sh itself and the m014-p01 bash32 gate which have
  # similar self-exemption needs (both scan for tokens and would match themselves).
  if [ "$bname" = "anti-pattern-lint.sh" ]; then continue; fi

  path="$PROJECT_ROOT/$f"
  if [ ! -f "$path" ]; then continue; fi

  # declare -A
  if grep -nE '^[[:space:]]*declare[[:space:]]+-A' "$path" >/dev/null 2>&1; then
    echo "FAIL: declare -A found in $f" >&2
    failed=$((failed + 1))
  fi
  # mapfile
  if grep -nE '^[[:space:]]*mapfile([[:space:]]|$)' "$path" >/dev/null 2>&1; then
    echo "FAIL: mapfile found in $f" >&2
    failed=$((failed + 1))
  fi
  # ${var,,} / ${var^^}
  if grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*,,' "$path" >/dev/null 2>&1; then
    echo "FAIL: \${var,,} found in $f" >&2
    failed=$((failed + 1))
  fi
  if grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*\^\^' "$path" >/dev/null 2>&1; then
    echo "FAIL: \${var^^} found in $f" >&2
    failed=$((failed + 1))
  fi
  # Process substitution <(...)
  if grep -nE '<\([^)]' "$path" >/dev/null 2>&1; then
    echo "FAIL: process substitution <(...) found in $f" >&2
    failed=$((failed + 1))
  fi
  # &>
  if grep -nE '&>' "$path" >/dev/null 2>&1; then
    echo "FAIL: &> redirect found in $f" >&2
    failed=$((failed + 1))
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "FAIL: $failed lint/bash32 violations" >&2
  exit 1
fi

echo "PASS: anti-pattern-lint + bash32-compat green across all P02 files"
exit 0
