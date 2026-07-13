#!/usr/bin/env sh
# m046-p02-atomic-write-discipline.sh (M046 FR-14 atomicity)
# Asserts BOTH marker writers — auto-loop.sh's outcome-marker writer and
# self-continue-drive.sh's child_abort writer — use the atomic temp+rename
# pattern (write to a .tmp path, then mv -f onto the final marker path), and
# that NO direct redirect to the final marker path exists in either writer.
# Plus a behavioral residue leg: a live gate-on write leaves the correct
# marker and no .tmp residue.
#
# Constraint (task T04): this verifier only REPORTS violations — fixes to
# the writers belong to the owning task's change-set (T01/T02).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUTO_LOOP="$REPO_ROOT/scripts/lifecycle/auto-loop.sh"
DRIVER="$REPO_ROOT/scripts/lifecycle/self-continue-drive.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m046-p02/verifying-tree/MFIX"

fails=0
passes=0
pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

[ -f "$AUTO_LOOP" ] || { echo "FAIL: auto-loop.sh not found: $AUTO_LOOP"; exit 1; }
[ -f "$DRIVER" ]    || { echo "FAIL: self-continue-drive.sh not found: $DRIVER"; exit 1; }
[ -d "$FIXTURE" ]   || { echo "FAIL: fixture tree not found: $FIXTURE"; exit 1; }

# ---------------------------------------------------------------------------
# Static shape leg — auto-loop.sh marker writer
# ---------------------------------------------------------------------------

# (a) temp path used: a line mentioning .self-continue-outcome.tmp exists.
n="$(grep -c '\.self-continue-outcome\.tmp' "$AUTO_LOOP" || true)"
if [ "$n" -ge 1 ]; then
  pass "auto-loop.sh: temp marker path (.self-continue-outcome.tmp) present ($n line(s))"
else
  fail "auto-loop.sh: no temp marker path (.self-continue-outcome.tmp) found"
fi

# (b) rename onto final path: an mv -f line mentioning .self-continue-outcome.
n="$(grep -c 'mv -f .*\.self-continue-outcome' "$AUTO_LOOP" || true)"
if [ "$n" -ge 1 ]; then
  pass "auto-loop.sh: mv -f rename onto final marker path present ($n line(s))"
else
  fail "auto-loop.sh: no mv -f rename onto final marker path found"
fi

# (c) NO direct redirect to the final marker path: zero lines with a `>`
#     redirect whose target ends in .self-continue-outcome (quoted or
#     unquoted; .tmp suffixed targets do not match). mv renames are the only
#     permitted writes to the final basename.
n="$(grep -cE '>[[:space:]]*("[^"]*\.self-continue-outcome"|[^"[:space:]]*\.self-continue-outcome([[:space:]]|$))' "$AUTO_LOOP" || true)"
if [ "$n" -eq 0 ]; then
  pass "auto-loop.sh: no direct redirect to final marker path (0 occurrences)"
else
  fail "auto-loop.sh: found $n direct redirect(s) to final marker path — writes must go temp+mv"
fi

# ---------------------------------------------------------------------------
# Static shape leg — self-continue-drive.sh child_abort writer
# ---------------------------------------------------------------------------

# (a) temp path used: _abort_tmp derived from $OUTCOME_FILE.tmp.
n="$(grep -c 'OUTCOME_FILE\.tmp' "$DRIVER" || true)"
if [ "$n" -ge 1 ]; then
  pass "self-continue-drive.sh: temp child_abort path (\$OUTCOME_FILE.tmp) present ($n line(s))"
else
  fail "self-continue-drive.sh: no temp child_abort path (\$OUTCOME_FILE.tmp) found"
fi

# (b) rename onto final path: mv -f "$_abort_tmp" "$OUTCOME_FILE".
n="$(grep -c 'mv -f "\$_abort_tmp" "\$OUTCOME_FILE"' "$DRIVER" || true)"
if [ "$n" -ge 1 ]; then
  pass "self-continue-drive.sh: mv -f rename onto \$OUTCOME_FILE present ($n line(s))"
else
  fail "self-continue-drive.sh: no mv -f rename onto \$OUTCOME_FILE found"
fi

# (c) NO direct redirect to $OUTCOME_FILE. Note: `rm -f "$OUTCOME_FILE"` is a
#     removal, not a write, and does not match this redirect pattern; the
#     $OUTCOME_FILE.tmp.$$ assignment carries no redirect either.
n="$(grep -cE '>[[:space:]]*"?\$OUTCOME_FILE"?([[:space:]]|$)' "$DRIVER" || true)"
if [ "$n" -eq 0 ]; then
  pass "self-continue-drive.sh: no direct redirect to \$OUTCOME_FILE (0 occurrences)"
else
  fail "self-continue-drive.sh: found $n direct redirect(s) to \$OUTCOME_FILE — writes must go temp+mv"
fi

# ---------------------------------------------------------------------------
# Behavioral residue leg — a live gate-on write leaves no temp residue
# ---------------------------------------------------------------------------

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

cp -R "$FIXTURE" "$scratch/MFIX"
rm -f "$scratch/MFIX/.self-continue-outcome"
touch "$scratch/MFIX/pause-requested"

rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$scratch/MFIX" >/dev/null 2>&1 || rc=$?

if [ "$rc" -eq 11 ]; then
  pass "behavioral: gate-on pause run exited 11"
else
  fail "behavioral: gate-on pause run expected exit 11, got $rc"
fi

marker_file="$scratch/MFIX/.self-continue-outcome"
if [ -f "$marker_file" ]; then
  got="$(cat "$marker_file")"
  if [ "$got" = "pause" ]; then
    pass "behavioral: marker content is exactly 'pause'"
  else
    fail "behavioral: marker content expected 'pause', got '$got'"
  fi
else
  fail "behavioral: marker file missing after gate-on pause run"
fi

residue="$(find "$scratch/MFIX" -name '.self-continue-outcome.tmp.*' | wc -l | tr -d ' ')"
if [ "$residue" -eq 0 ]; then
  pass "behavioral: no .self-continue-outcome.tmp.* residue in scratch tree"
else
  fail "behavioral: found $residue temp residue file(s) in scratch tree"
fi

if [ "$fails" -eq 0 ]; then
  echo "PASS: m046-p02-atomic-write-discipline — $passes/9 checks green"
  exit 0
else
  echo "FAIL: m046-p02-atomic-write-discipline — $fails check(s) failed ($passes passed)"
  exit 1
fi
