#!/usr/bin/env sh
# m046-p04-fail-closed.sh (M046 P04 phase Truth 1 / SC-8 / FR-13)
#
# The FR-13 refuse-to-start gate lives IN THE DRIVER, not in a CLI wrapper.
# Every case here invokes scripts/lifecycle/self-continue-drive.sh DIRECTLY
# (sh DRIVER <scratch-M> ...) — that direct invocation IS the bypass-the-CLI
# path SC-8 requires. Under --unattended the driver MUST refuse (exit 2,
# SELF_CONTINUE:REFUSE, no ledger, no spawn) whenever the budget cap,
# --max-continuations, or --max-wall-clock-s is unset or non-numeric; the
# silent MAX_CONT=20 default must be DEAD on the unattended path. A "no spawn"
# claim is made falsifiable by handing every case a stub --auto-cmd child that
# touches a sentinel — refusal keeps the sentinel absent, a passing gate lets
# the child run and the sentinel appear.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="$REPO_ROOT/scripts/lifecycle/self-continue-drive.sh"

[ -f "$DRIVER" ] || { echo "FAIL: driver not found: $DRIVER"; exit 1; }

passes=0
fails=0
pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# Trivial well-behaved child: touch the sentinel, write a terminal `complete`
# marker, print its authoritative cost JSON on stdout, exit clean. $1 is the
# milestone dir (whitespace-free mktemp path, passed via --auto-cmd).
STUB="$scratch/child-stub.sh"
cat > "$STUB" <<'EOF'
#!/usr/bin/env sh
MDIR="$1"
: > "$MDIR/sentinel"
printf 'complete\n' > "$MDIR/.self-continue-outcome"
printf '{"type":"result","total_cost_usd":0.01}\n'
exit 0
EOF
chmod +x "$STUB"

# new_mdir <name> — a fresh milestone dir for one case.
new_mdir() { d="$scratch/$1"; mkdir -p "$d"; printf '%s' "$d"; }

# --- Case 1: --unattended, NO caps at all -> refuse, full missing csv ---------
M="$(new_mdir c1)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --unattended 2>/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] \
   && printf '%s' "$OUT" | grep -q 'SELF_CONTINUE:REFUSE' \
   && printf '%s' "$OUT" | grep -q 'reason=caps-unset' \
   && printf '%s' "$OUT" | grep -q 'budget' \
   && printf '%s' "$OUT" | grep -q 'continuations' \
   && printf '%s' "$OUT" | grep -q 'wall-clock' \
   && [ ! -f "$M/sentinel" ] \
   && [ ! -f "$M/.self-continue-budget-ledger" ]; then
  pass "no-caps -> exit 2 REFUSE caps-unset (all three named), no spawn, no ledger"
else
  fail "no-caps rc=$RC out='$OUT' sentinel=$([ -f "$M/sentinel" ] && echo yes || echo no) ledger=$([ -f "$M/.self-continue-budget-ledger" ] && echo yes || echo no)"
fi

# --- Case 2: budget missing (cont + wall present) -> missing=budget only ------
M="$(new_mdir c2)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --unattended --max-continuations 3 --max-wall-clock-s 60 2>/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] \
   && printf '%s' "$OUT" | grep -q 'reason=caps-unset missing=budget$' \
   && [ ! -f "$M/sentinel" ]; then
  pass "budget-missing -> REFUSE missing=budget only, no spawn"
else
  fail "budget-missing rc=$RC out='$OUT'"
fi

# --- Case 3: continuations missing -> proves silent MAX_CONT=20 is DEAD -------
M="$(new_mdir c3)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --unattended --max-budget-usd 5 --max-wall-clock-s 60 2>/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] \
   && printf '%s' "$OUT" | grep -q 'reason=caps-unset missing=continuations$' \
   && [ ! -f "$M/sentinel" ]; then
  pass "continuations-missing -> REFUSE missing=continuations (silent MAX_CONT=20 default rejected)"
else
  fail "continuations-missing rc=$RC out='$OUT'"
fi

# --- Case 4: wall-clock missing -> missing=wall-clock -------------------------
M="$(new_mdir c4)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --unattended --max-budget-usd 5 --max-continuations 3 2>/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] \
   && printf '%s' "$OUT" | grep -q 'reason=caps-unset missing=wall-clock$' \
   && [ ! -f "$M/sentinel" ]; then
  pass "wall-clock-missing -> REFUSE missing=wall-clock, no spawn"
else
  fail "wall-clock-missing rc=$RC out='$OUT'"
fi

# --- Case 5: budget non-numeric -> caps-invalid ------------------------------
M="$(new_mdir c5)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --unattended --max-budget-usd abc --max-continuations 3 --max-wall-clock-s 60 2>/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] \
   && printf '%s' "$OUT" | grep -q 'reason=caps-invalid' \
   && printf '%s' "$OUT" | grep -q 'invalid=budget' \
   && [ ! -f "$M/sentinel" ]; then
  pass "budget=abc -> exit 2 REFUSE caps-invalid invalid=budget, no spawn"
else
  fail "budget-invalid rc=$RC out='$OUT'"
fi

# --- Case 6: all three caps valid + trivial child -> runs to TERMINAL ---------
# Proves the refusal is cap-driven, not merely --unattended-driven.
M="$(new_mdir c6)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --unattended --max-budget-usd 5 --max-continuations 3 --max-wall-clock-s 60 2>/dev/null)" || RC=$?
if [ "$RC" -eq 0 ] \
   && [ -f "$M/sentinel" ] \
   && printf '%s' "$OUT" | grep -q 'SELF_CONTINUE:TERMINAL outcome=complete' \
   && ! printf '%s' "$OUT" | grep -q 'SELF_CONTINUE:REFUSE'; then
  pass "all-caps-valid -> child spawns (sentinel present), TERMINAL outcome=complete"
else
  fail "all-caps-valid rc=$RC out='$OUT' sentinel=$([ -f "$M/sentinel" ] && echo yes || echo no)"
fi

# --- Case 7: attended control -- same missing caps WITHOUT --unattended -------
# FR-6/FR-17: the gate binds ONLY the unattended path; attended ignores caps.
M="$(new_mdir c7)"
RC=0
OUT="$(sh "$DRIVER" "$M" --min-interval 0 --auto-cmd "sh $STUB $M" --max-continuations 3 2>/dev/null)" || RC=$?
if [ -f "$M/sentinel" ] \
   && ! printf '%s' "$OUT" | grep -q 'SELF_CONTINUE:REFUSE'; then
  pass "attended (no --unattended) with missing caps -> runs, no REFUSE (gate binds only unattended)"
else
  fail "attended-control rc=$RC out='$OUT' sentinel=$([ -f "$M/sentinel" ] && echo yes || echo no)"
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
