#!/usr/bin/env bash
# scripts/verify/m018-p00-fixture-replay.sh -- M018/P00/T03 synthetic
# fixture-replay harness for emitter parity validation.
#
# Background: Path A (counting parity over 20 organic dispatches in the
# production milestones tree) requires accumulated traffic that does not
# yet exist post-T01. Path B replays build-context.sh against a small
# in-memory fixture 20 times against a scratch execution-log, then runs
# the T01 parity verifier against that scratch log via the verifier's
# `--root` flag.
#
# This is a closed-loop, deterministic mechanism: the fixture milestone
# is copied from tests/fixtures/dispatch-state, the scratch root is
# wiped on each run, build-context.sh is invoked 20 times, and the
# parity verifier asserts >= 95% parity over the 20-record window.
#
# Usage:
#   m018-p00-fixture-replay.sh [--iterations N] [--threshold P]
#
#   --iterations N -- number of build-context.sh invocations (default 20).
#   --threshold P  -- parity threshold percent (default 95).
#
# Output:
#   PASS: fixture-replay parity (N invocations) -- <P>%
#   FAIL: fixture-replay parity below threshold ...
#
# Exit 0 on parity >= threshold, 1 otherwise.
#
# AD-19 single-script-file shape. Bash 3.2 / POSIX-friendly.

set -u

ITERATIONS=20
THRESHOLD=95

while [ $# -gt 0 ]; do
  case "$1" in
    --iterations) ITERATIONS="${2:-20}"; shift 2 ;;
    --threshold)  THRESHOLD="${2:-95}";  shift 2 ;;
    -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
    *)            shift ;;
  esac
done

case "$ITERATIONS" in
  ''|*[!0-9]*) printf 'FAIL: m018-p00-fixture-replay invalid-iterations=%s\n' "$ITERATIONS" >&2; exit 1 ;;
esac
case "$THRESHOLD" in
  ''|*[!0-9]*) printf 'FAIL: m018-p00-fixture-replay invalid-threshold=%s\n' "$THRESHOLD" >&2; exit 1 ;;
esac

N=$((10#$ITERATIONS))
T=$((10#$THRESHOLD))

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FIXTURE_SRC="$REPO_ROOT/tests/fixtures/dispatch-state"
PARITY_VERIFIER="$REPO_ROOT/scripts/verify/m018-p00-emitter-parity.sh"
BUILD_CONTEXT="$REPO_ROOT/scripts/dispatch/build-context.sh"

if [ ! -d "$FIXTURE_SRC" ]; then
  printf 'FAIL: m018-p00-fixture-replay fixture-source-missing path=%s\n' "$FIXTURE_SRC" >&2
  exit 1
fi
if [ ! -x "$PARITY_VERIFIER" ] && [ ! -r "$PARITY_VERIFIER" ]; then
  printf 'FAIL: m018-p00-fixture-replay parity-verifier-missing path=%s\n' "$PARITY_VERIFIER" >&2
  exit 1
fi
if [ ! -r "$BUILD_CONTEXT" ]; then
  printf 'FAIL: m018-p00-fixture-replay build-context-missing path=%s\n' "$BUILD_CONTEXT" >&2
  exit 1
fi

REPLAY_ROOT="$REPO_ROOT/.orchestrator/scratch/m018-p00-replay-root"
SCRATCH_LOG="$REPO_ROOT/.orchestrator/scratch/m018-p00-fixture-log.jsonl"

rm -rf "$REPLAY_ROOT"
mkdir -p "$REPLAY_ROOT"

# Copy fixture into a fake milestones-style tree:
#   $REPLAY_ROOT/M001/<phases,roadmap,...>
# build-context.sh fixture-mode: if ORCH_ROOT/phases exists and ORCH_ROOT
# is not under .../milestones/<M###>, it logs to ORCH_ROOT/execution-log.jsonl.
FIXTURE_DST="$REPLAY_ROOT/M001"
cp -R "$FIXTURE_SRC" "$FIXTURE_DST"
rm -f "$FIXTURE_DST/execution-log.jsonl"

i=0
fail_count=0
while [ "$i" -lt "$N" ]; do
  bash "$BUILD_CONTEXT" "$FIXTURE_DST" M001 P02 T01 >/dev/null 2>"$REPLAY_ROOT/_err.$i.log"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail_count=$((fail_count + 1))
  fi
  i=$((i + 1))
done

if [ ! -r "$FIXTURE_DST/execution-log.jsonl" ]; then
  printf 'FAIL: m018-p00-fixture-replay no-log-emitted iterations=%d failed=%d\n' "$N" "$fail_count" >&2
  exit 1
fi

# Mirror to canonical scratch log path for audit-trail visibility.
cp "$FIXTURE_DST/execution-log.jsonl" "$SCRATCH_LOG"

# Run the parity verifier against the replay root.
bash "$PARITY_VERIFIER" --window "$N" --threshold "$T" --root "$REPLAY_ROOT"
rc=$?

if [ "$rc" -eq 0 ]; then
  printf 'PASS: fixture-replay parity (%d invocations against %s)\n' "$N" "$REPLAY_ROOT"
  exit 0
fi

printf 'FAIL: fixture-replay parity below threshold (%d invocations, %d build failures)\n' "$N" "$fail_count" >&2
exit 1
