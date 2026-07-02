#!/usr/bin/env sh
# SC-1: a completed multi-segment run is auditable as one continuous execution.
set -eu
D="scripts/lifecycle/self-continue-drive.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MDIR="$TMP/M"; mkdir -p "$MDIR"; LOG="$TMP/sc.log"
# Stub: rotate on advancing phases for 2 segments, then complete.
STUB="$TMP/stub.sh"
printf '#!/usr/bin/env sh\nN=$(cat "%s/n" 2>/dev/null || echo 0); N=$((N+1)); echo "$N" > "%s/n"\nif [ "$N" -le 2 ]; then printf "rotation P%%s" "$N" > "%s/.self-continue-outcome"; else printf "complete" > "%s/.self-continue-outcome"; fi\n' "$TMP" "$TMP" "$MDIR" "$MDIR" > "$STUB"
chmod +x "$STUB"
sh "$D" "$MDIR" --min-interval 0 --log "$LOG" --auto-cmd "sh $STUB" >/dev/null
SCHED="$(grep -c 'self_continue_scheduled' "$LOG" 2>/dev/null || echo 0)"
[ "$SCHED" -ge 2 ] || { echo "FAIL: expected >=2 self_continue_scheduled, got $SCHED"; exit 1; }
grep -q 'self_continue_terminal' "$LOG" || { echo "FAIL: no terminal record"; exit 1; }
grep -q 'human' "$LOG" && { echo "FAIL: unexpected human-reinvoke marker in continuous log"; exit 1; }
echo "PASS: multi-segment run auditable as one continuous execution ($SCHED scheduled + terminal)"
