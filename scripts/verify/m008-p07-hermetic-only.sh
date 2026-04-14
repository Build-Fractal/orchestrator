#!/usr/bin/env bash
# scripts/verify/m008-p07-hermetic-only.sh
# Static hermetic-only gate: every P07 verification script that exercises the
# init/reinit pipeline must use mktemp -d fixtures and must set HOME= to a
# fixture path before invoking init-project.sh. Purely static checks (docs,
# contracts, interface shape) are exempt.
#
# This gate prevents regressions where a newly-added P07 verifier would write
# into the developer's real $HOME (skills dir, commands dir) during test runs.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_DIR="$REPO_ROOT/scripts/verify"

FAIL=0
CHECKED=0

for f in "$VERIFY_DIR"/m008-p07-*.sh; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"

  # Exempt static-only checks (no init/reinit invocation).
  case "$base" in
    m008-p07-bash32-compat.sh|\
    m008-p07-hermetic-only.sh|\
    m008-p07-detect-project-contract.sh|\
    m008-p07-detect-project-matrix.sh|\
    m008-p07-project-instruction-template.sh|\
    m008-p07-init-command-doc.sh|\
    m008-p07-init-interface.sh|\
    m008-p07-instruction-file-routing.sh)
      continue ;;
  esac

  CHECKED=$(( CHECKED + 1 ))

  # Must use mktemp -d somewhere for fixture creation.
  if ! grep -q 'mktemp -d' "$f"; then
    echo "FAIL: $base does not use mktemp -d fixtures" >&2
    FAIL=1
  fi

  # If it invokes init-project.sh or reinit-handler.sh, it must set HOME= to
  # a fixture variable (FIXTURE_HOME) or directly to an mktemp path before
  # the invocation. We check for the lexical presence of such an assignment.
  if grep -qE '(init-project|reinit-handler)\.sh' "$f"; then
    # Accept: HOME="$FIXTURE_HOME", HOME=$FIXTURE_HOME, HOME="$(mktemp ...)"
    if ! grep -qE 'HOME="\$FIXTURE_HOME"' "$f" \
       && ! grep -qE 'HOME=\$FIXTURE_HOME' "$f" \
       && ! grep -qE 'HOME="\$\(mktemp' "$f"; then
      echo "FAIL: $base invokes init-project.sh/reinit-handler.sh without setting HOME= to a fixture" >&2
      FAIL=1
    fi
  fi
done

if [ "$CHECKED" -eq 0 ]; then
  echo "FAIL: no P07 integration verifiers found to scan" >&2
  exit 1
fi

if [ $FAIL -eq 0 ]; then
  echo "PASS: all P07 integration tests are hermetic (checked=$CHECKED)"
  exit 0
fi

exit 1
