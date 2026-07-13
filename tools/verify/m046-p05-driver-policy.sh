#!/usr/bin/env bash
# tools/verify/m046-p05-driver-policy.sh -- M046/P05/T03 unit verifier.
#
# Proves the driver's per-run write/tool-scope policy composition (Decision
# D018) and the child env export (ORCHESTRATOR_UNATTENDED_POLICY), the wiring
# the T01 hook enforces:
#
#   * FUNCTION LEG: source scripts/lifecycle/unattended-envelope.sh and drive
#     envelope_write_scope_policy against the REAL committed manifest
#     scripts/hooks/unattended-protected-surface.txt in a mktemp scratch.
#     Assert the composed policy carries allow_path <root>/, a readonly_path
#     line for every manifest glob (specs/ tools/verify/ scripts/verify/
#     scripts/hooks/), the roadmap SC surface, the policy-file self-line (no
#     self-widening), the P07 FORWARD-SLOT comment when the attempts-ledger is
#     absent AND the promoted readonly_path line when a stub ledger exists, and
#     NO allow_tool line (MCP default-DENY, D019) / NO allow_bash line.
#   * DRIVER STATIC LEG: grep scripts/lifecycle/self-continue-drive.sh for the
#     composition call + the ORCHESTRATOR_UNATTENDED_POLICY export sitting
#     inside the unattended run_child env block (adjacent to
#     ORCHESTRATOR_UNATTENDED=1).
#   * ATTENDED-PARITY LEG (FR-17): assert the attended child spawn line
#     (ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@" ...) carries NO
#     ORCHESTRATOR_UNATTENDED_POLICY -- the attended path composes/exports none.
#   * LIVE-DRIVE LEG: drive the REAL driver under --unattended against a mktemp
#     scratch milestone tree with a stub --auto-cmd (no claude -p spawn), and
#     inspect that the child received ORCHESTRATOR_UNATTENDED_POLICY pointing at
#     the composed <milestone-dir>/.self-continue-scope-policy.
#
# Verifiers may contain any bash shape; only Truth `Check:` lines are AD-19
# shape-constrained. Bash 3.2. No jq. Scratch/mktemp trees only -- never the
# repo lock, never .orchestrator/milestones/M046.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

DRIVER="scripts/lifecycle/self-continue-drive.sh"
ENVELOPE="scripts/lifecycle/unattended-envelope.sh"
MANIFEST="scripts/hooks/unattended-protected-surface.txt"

pass=0
fail=0

ok()   { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }

# assert_grep <label> <pattern> <file>   -- fixed-string presence
assert_grep() {
  if grep -qF "$2" "$3" 2>/dev/null; then ok "$1"; else bad "$1"; fi
}
# assert_no_grep <label> <pattern> <file>
assert_no_grep() {
  if grep -qF "$2" "$3" 2>/dev/null; then bad "$1"; else ok "$1"; fi
}
# assert_no_grep_re <label> <ere> <file>
assert_no_grep_re() {
  if grep -Eq "$2" "$3" 2>/dev/null; then bad "$1"; else ok "$1"; fi
}

# =============================================================================
# FUNCTION LEG
# =============================================================================
# shellcheck disable=SC1090
. "$ENVELOPE"

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/m046p05t03.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

FAKEROOT="$SCRATCH/proj"
MDIR="$SCRATCH/mdir"
mkdir -p "$FAKEROOT" "$MDIR"
POLICY="$MDIR/.self-continue-scope-policy"
ROAD="$MDIR/road-ROADMAP.md"
: > "$ROAD"

# Compose with the P07 attempts-ledger ABSENT.
envelope_write_scope_policy "$POLICY" "$FAKEROOT" "$MANIFEST" "$MDIR" "$ROAD" ""

printf -- '--- composed policy (ledger absent) ---\n'
cat "$POLICY"
printf -- '---------------------------------------\n'

assert_grep "fn: allow_path project-root" "allow_path $FAKEROOT/" "$POLICY"
assert_grep "fn: readonly_path specs/ (manifest glob)"        "readonly_path $FAKEROOT/specs/"         "$POLICY"
assert_grep "fn: readonly_path tools/verify/ (manifest glob)" "readonly_path $FAKEROOT/tools/verify/"  "$POLICY"
assert_grep "fn: readonly_path scripts/verify/ (manifest glob)" "readonly_path $FAKEROOT/scripts/verify/" "$POLICY"
assert_grep "fn: readonly_path scripts/hooks/ (manifest glob)"  "readonly_path $FAKEROOT/scripts/hooks/"  "$POLICY"
assert_grep "fn: readonly_path roadmap SC surface" "readonly_path $ROAD" "$POLICY"
assert_grep "fn: readonly_path policy self-line (no self-widening)" "readonly_path $POLICY" "$POLICY"
assert_grep "fn: P07 FORWARD-SLOT comment placeholder" "# P07 FORWARD-SLOT readonly_path $MDIR/.self-continue-attempts-ledger" "$POLICY"
assert_no_grep_re "fn: no allow_tool line (MCP default-DENY, D019)" "^allow_tool" "$POLICY"
assert_no_grep_re "fn: no allow_bash line" "^allow_bash" "$POLICY"

# The forward-slot is a COMMENT, not an active readonly_path, while absent.
if grep -Eq "^readonly_path $MDIR/\.self-continue-attempts-ledger$" "$POLICY"; then
  bad "fn: attempts-ledger NOT an active readonly_path while absent"
else
  ok  "fn: attempts-ledger NOT an active readonly_path while absent"
fi

# Compose with a STUB attempts-ledger PRESENT -> forward-slot promotes to an
# active readonly_path directive (P07 forward-slot behavior).
LEDGER="$MDIR/.self-continue-attempts-ledger"
: > "$LEDGER"
envelope_write_scope_policy "$POLICY" "$FAKEROOT" "$MANIFEST" "$MDIR" "$ROAD" ""
printf -- '--- composed policy (ledger present) ---\n'
cat "$POLICY"
printf -- '----------------------------------------\n'
if grep -Eq "^readonly_path $MDIR/\.self-continue-attempts-ledger$" "$POLICY"; then
  ok  "fn: attempts-ledger promoted to active readonly_path when present"
else
  bad "fn: attempts-ledger promoted to active readonly_path when present"
fi
assert_no_grep "fn: P07 comment placeholder gone when ledger present" "# P07 FORWARD-SLOT readonly_path" "$POLICY"
rm -f "$LEDGER"

# =============================================================================
# DRIVER STATIC LEG
# =============================================================================
assert_grep "driver: calls envelope_write_scope_policy" "envelope_write_scope_policy" "$DRIVER"
assert_grep "driver: references ORCHESTRATOR_UNATTENDED_POLICY" "ORCHESTRATOR_UNATTENDED_POLICY" "$DRIVER"

# Adjacency: the export sits inside the unattended run_child env block, right
# after ORCHESTRATOR_UNATTENDED=1 (two separate greps to isolate the region).
if grep -A2 'ORCHESTRATOR_UNATTENDED=1 \\' "$DRIVER" | grep -q 'ORCHESTRATOR_UNATTENDED_POLICY'; then
  ok  "driver: export adjacent to ORCHESTRATOR_UNATTENDED=1 (unattended env block)"
else
  bad "driver: export adjacent to ORCHESTRATOR_UNATTENDED=1 (unattended env block)"
fi

# =============================================================================
# ATTENDED-PARITY LEG (FR-17)
# =============================================================================
# The attended child spawn line must carry NO policy export.
ATT_LINE="$(grep 'ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "\$@"' "$DRIVER" || true)"
if [ -n "$ATT_LINE" ]; then
  if printf '%s' "$ATT_LINE" | grep -q 'ORCHESTRATOR_UNATTENDED_POLICY'; then
    bad "attended: spawn line MUST NOT carry ORCHESTRATOR_UNATTENDED_POLICY"
  else
    ok  "attended: spawn line carries no ORCHESTRATOR_UNATTENDED_POLICY (FR-17)"
  fi
else
  bad "attended: could not locate the attended spawn line"
fi

# =============================================================================
# LIVE-DRIVE LEG -- drive the REAL driver, inspect the exported var
# =============================================================================
LIVE="$SCRATCH/live"
mkdir -p "$LIVE"
PROBE="$LIVE/probe.sh"
cat > "$PROBE" <<'PROBE_EOF'
#!/usr/bin/env sh
# Stub child: dump the policy-relevant env into probe-env.txt, then write a
# terminal outcome so the driver exits after one segment.
_d="$(cd "$(dirname "$0")" && pwd)"
{
  printf 'ORCHESTRATOR_UNATTENDED=%s\n' "${ORCHESTRATOR_UNATTENDED:-<unset>}"
  printf 'ORCHESTRATOR_UNATTENDED_POLICY=%s\n' "${ORCHESTRATOR_UNATTENDED_POLICY:-<unset>}"
} > "$_d/probe-env.txt"
printf 'complete\n' > "$_d/.self-continue-outcome"
PROBE_EOF
chmod +x "$PROBE"

# Drive: --unattended (fail-closed caps supplied) with a stub --auto-cmd so no
# claude -p is spawned. min-interval 0, one continuation, generous caps.
bash "$DRIVER" "$LIVE" --unattended \
  --max-budget-usd 10 --max-continuations 1 --max-wall-clock-s 60 \
  --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $PROBE" > "$SCRATCH/live.out" 2>&1 || true

LIVE_POLICY="$LIVE/.self-continue-scope-policy"
if [ -f "$LIVE_POLICY" ]; then
  ok "live: driver composed <milestone-dir>/.self-continue-scope-policy"
else
  bad "live: driver composed <milestone-dir>/.self-continue-scope-policy"
fi

PROBE_ENV="$LIVE/probe-env.txt"
if [ -f "$PROBE_ENV" ]; then
  assert_grep "live: child received ORCHESTRATOR_UNATTENDED=1" "ORCHESTRATOR_UNATTENDED=1" "$PROBE_ENV"
  assert_grep "live: child received ORCHESTRATOR_UNATTENDED_POLICY=<composed policy>" \
    "ORCHESTRATOR_UNATTENDED_POLICY=$LIVE_POLICY" "$PROBE_ENV"
else
  bad "live: stub child did not run (probe-env.txt absent)"
  printf -- '--- driver output ---\n'
  cat "$SCRATCH/live.out"
  printf -- '---------------------\n'
fi

printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
