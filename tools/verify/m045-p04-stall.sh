#!/usr/bin/env sh
# SC-7: a segment that produces no outcome surfaces as SELF_CONTINUE:STALLED.
set -eu
D="scripts/lifecycle/self-continue-drive.sh"
S="scripts/diagnostics/self-continue-status.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MDIR="$TMP/M"; mkdir -p "$MDIR"; LOG="$TMP/sc.log"
# Stub that never writes an outcome marker (simulates a crashed fresh segment).
NOOP="$TMP/noop.sh"
printf '#!/usr/bin/env sh\nexit 0\n' > "$NOOP"; chmod +x "$NOOP"
RES="$(sh "$D" "$MDIR" --min-interval 0 --log "$LOG" --auto-cmd "sh $NOOP")"
case "$RES" in
  *"SELF_CONTINUE:STALLED"*) : ;;
  *) echo "FAIL: expected SELF_CONTINUE:STALLED from driver, got: $RES"; exit 1 ;;
esac
ST="$(sh "$S" "$LOG")"
case "$ST" in
  *"SELF_CONTINUE:STALLED"*) : ;;
  *) echo "FAIL: status reader did not report STALLED, got: $ST"; exit 1 ;;
esac
echo "PASS: stall surfaced by driver and status reader"
