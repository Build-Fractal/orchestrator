#!/usr/bin/env bash
# scripts/verify/m027-p03-read-only.sh -- M027/P03 Truth #10.
#
# Asserts CON-1 / FR-12 read-only invariant: invoking the M027/P03
# helpers (check-anomalies.sh, check-config-drift.sh) and run-doctor.sh
# --config-check leaves the project tree clean. Captures `git diff
# --quiet` exit before and after a sequence of read-only invocations.
#
# Exclusion: run-doctor.sh appends to .orchestrator/doctor-history.jsonl
# as a pre-existing pre-T03 side-effect. We pathspec-exclude that file
# from the post-run diff so the verifier asserts only the M027/P03
# helpers themselves are read-only.
#
# If the working tree is already dirty pre-run, emits a WARN line and
# exits 0 (the verifier cannot distinguish surface-induced dirt from
# pre-existing dirt). Mirrors the M027/P01/T04 + P02/T04 read-only
# verifier WARN-skip-on-dirty pattern.
#
# Bash 3.2 compatible. MEM004 carve-out -- git used internally.

set -u

NAME="m027-p03-read-only.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

PATHSPEC_EXCL=":!.orchestrator/doctor-history.jsonl"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if ! command -v git >/dev/null 2>&1; then
  echo "WARN: $NAME git not available; skipping read-only assertion"
  exit 0
fi

git diff --quiet -- "$PATHSPEC_EXCL"
pre_rc=$?
if [ "$pre_rc" -ne 0 ]; then
  echo "WARN: $NAME working-tree-dirty pre-run; skipping read-only assertion"
  exit 0
fi

# Read-only invocations.
bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013 >/dev/null 2>&1 || true
bash scripts/diagnostics/check-anomalies.sh --milestone M013 >/dev/null 2>&1 || true
bash scripts/diagnostics/check-config-drift.sh >/dev/null 2>&1 || true
bash scripts/diagnostics/check-config-drift.sh --no-config-check >/dev/null 2>&1 || true
bash scripts/diagnostics/run-doctor.sh --config-check --no-anomaly >/dev/null 2>&1 || true

git diff --quiet -- "$PATHSPEC_EXCL"
post_rc=$?
if [ "$post_rc" -ne 0 ]; then
  printf 'DIRT:\n' >&2
  git diff --stat -- "$PATHSPEC_EXCL" >&2 || true
  fail "working tree dirty after helper invocations"
fi

echo "PASS: $NAME"
exit 0
