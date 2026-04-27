#!/usr/bin/env bash
# scripts/verify/m027-p02-read-only.sh -- M027/P02 Truth #10.
#
# Asserts CON-1 / FR-12 read-only invariant: invoking the M027/P02
# helpers (efficiency-footer.sh, predictive-surface.sh) leaves the
# project tree clean. Captures `git diff --quiet` exit before and after a
# sequence of read-only invocations.
#
# If the working tree is already dirty pre-run, emits a WARN line and
# exits 0 (the verifier cannot distinguish surface-induced dirt from
# pre-existing dirt). Mirrors the M027/P01/T04 read-only verifier's
# WARN-skip-on-dirty pattern.
#
# Bash 3.2 compatible. MEM004 carve-out -- git used internally.

set -u

NAME="m027-p02-read-only.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if ! command -v git >/dev/null 2>&1; then
  echo "WARN: $NAME git not available; skipping read-only assertion"
  exit 0
fi

git diff --quiet
pre_rc=$?
if [ "$pre_rc" -ne 0 ]; then
  echo "WARN: $NAME working-tree-dirty pre-run; skipping read-only assertion"
  exit 0
fi

# Read-only invocations.
bash scripts/diagnostics/efficiency-footer.sh --quiet >/dev/null 2>&1 || true
bash scripts/diagnostics/efficiency-footer.sh --milestone M019 >/dev/null 2>&1 || true
bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard >/dev/null 2>&1 || true
bash scripts/dispatch/predictive-surface.sh --description "test" --intensity standard --yes >/dev/null 2>&1 || true

git diff --quiet
post_rc=$?
if [ "$post_rc" -ne 0 ]; then
  printf 'DIRT:\n' >&2
  git diff --stat >&2 || true
  fail "working tree dirty after helper invocations"
fi

echo "PASS: $NAME"
exit 0
