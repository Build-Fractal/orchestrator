#!/usr/bin/env bash
# scripts/verify/m026-p02-gate-verdict-reliability.sh
#
# M026/P02/T04 gate: verify the conversus adapter closes POST-P01-FINDINGS
# F1 (rationale from `## Verdict` text), F2 (prefer arbiter/resolution.md),
# and F3 (auto-preflight CONVERSUS_PROVIDER=claude-code under OAuth).
#
# Assertions:
#   F1 static: adapter source carries the awk-based `## Verdict` extractor
#              and the synthesized-formula fallback.
#   F1 smoke : driving the same awk block (copied from adapter) against a
#              synthetic synthesis file produces the expected paragraph.
#   F2 static: adapter source references arbiter/resolution.md and prefers
#              it as the verdict source when present.
#   F2 smoke : with both arbiter/resolution.md and summary/final.md, the
#              arbiter file's Verdict paragraph wins.
#   F3 static: preflight block present with correct env-var gates
#              (CONVERSUS_PROVIDER+set, ANTHROPIC_API_KEY, .conversus/auth.json,
#              claude-code assignment, stderr note:).
#   F3 smoke : replay the same detection heuristic in isolation against a
#              synthetic HOME with a mock auth.json — assert OAuth-marker
#              presence triggers the rule and operator-set CONVERSUS_PROVIDER
#              suppresses it.
#
# Scope note: the F3 auto-preflight lives deep inside the `gate` subcommand
# (after synth+binary-resolve). A full end-to-end smoke requires a real
# conversus binary and a valid synth run. This verifier scopes F3 to
# (a) static pattern verification of the adapter source, and (b) a
# standalone replay of the same detection heuristic — which together pin
# the contract. Full `gate`-path integration remains covered by
# tests/test-conversus-adapter-shim.sh.
#
# Bash 3.2 compatible. Single-script-file shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1" >&2; failed=$((failed + 1)); }

if [ ! -f "$ADAPTER" ]; then
  fail "adapter missing: $ADAPTER"
  echo "FAIL: m026-p02-gate-verdict-reliability.sh" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t m026-p02-gvr.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# ---------------------------------------------------------------------------
# F1 static: adapter carries the awk `## Verdict` extractor + fallback.
# ---------------------------------------------------------------------------
if grep -qE '/\^## Verdict/ \{ capture=1; next \}' "$ADAPTER"; then
  pass "F1 static: awk `## Verdict` section extractor present"
else
  fail "F1 static: awk `## Verdict` section extractor missing"
fi

if grep -qE 'verdict=\$\{_verdict\} derived from surviving_disputes' "$ADAPTER"; then
  pass "F1 static: synthesized-formula fallback preserved"
else
  fail "F1 static: synthesized-formula fallback missing"
fi

if grep -qE 'if \[ -n "\$_rationale_text" \]; then' "$ADAPTER"; then
  pass "F1 static: prefer-extracted-rationale guard present"
else
  fail "F1 static: prefer-extracted-rationale guard missing"
fi

# ---------------------------------------------------------------------------
# F1 smoke: replay the awk extraction against a synthetic synthesis file.
# ---------------------------------------------------------------------------
SYN_DIR="${SCRATCH}/f1-smoke"
mkdir -p "$SYN_DIR"
SYN_FILE="${SYN_DIR}/final.md"
cat > "$SYN_FILE" <<'EOF'
# Synthesis

Some preamble.

## Verdict

BLOCK: the proposal fails Principle II. Red team attacks escalated; zero
withdrawn. Route through orchestrator:discuss for scope revision.

## Supporting evidence

Details follow here.
EOF

F1_SMOKE_TEXT="$(awk '
  /^## Verdict/ { capture=1; next }
  /^## / && capture { exit }
  capture && NF { out = out (out=="" ? "" : " ") $0 }
  END { print out }
' "$SYN_FILE" 2>/dev/null)"
F1_SMOKE_TEXT="$(printf '%s\n' "$F1_SMOKE_TEXT" | sed -E 's/"/\x27/g; s/[[:space:]]+/ /g; s/^ *//; s/ *$//')"

case "$F1_SMOKE_TEXT" in
  "BLOCK: the proposal fails Principle II."*)
    pass "F1 smoke: extractor captures first paragraph of Verdict section"
    ;;
  *)
    fail "F1 smoke: extracted text unexpected: [${F1_SMOKE_TEXT}]"
    ;;
esac

# F1 smoke fallback: Verdict section absent → extractor yields empty.
SYN_NOV="${SYN_DIR}/no-verdict.md"
cat > "$SYN_NOV" <<'EOF'
# Synthesis

Only prose here, no Verdict heading.
EOF

F1_NOV_TEXT="$(awk '
  /^## Verdict/ { capture=1; next }
  /^## / && capture { exit }
  capture && NF { out = out (out=="" ? "" : " ") $0 }
  END { print out }
' "$SYN_NOV" 2>/dev/null)"
F1_NOV_TEXT="$(printf '%s\n' "$F1_NOV_TEXT" | sed -E 's/[[:space:]]+/ /g; s/^ *//; s/ *$//')"

if [ -z "$F1_NOV_TEXT" ]; then
  pass "F1 smoke: no Verdict section → empty (fallback will fire)"
else
  fail "F1 smoke: expected empty, got [${F1_NOV_TEXT}]"
fi

# ---------------------------------------------------------------------------
# F2 static: adapter prefers arbiter/resolution.md.
# ---------------------------------------------------------------------------
if grep -qE '_arbiter_file="\$\{_run_output_dir\}/arbiter/resolution\.md"' "$ADAPTER"; then
  pass "F2 static: arbiter/resolution.md path computed"
else
  fail "F2 static: arbiter/resolution.md path missing"
fi

if grep -qE 'if \[ -f "\$_arbiter_file" \]; then' "$ADAPTER"; then
  pass "F2 static: arbiter-file existence branch present"
else
  fail "F2 static: arbiter-file existence branch missing"
fi

if grep -qE '_verdict_source="\$_arbiter_file"' "$ADAPTER" && \
   grep -qE '_verdict_source="\$_synthesis"' "$ADAPTER"; then
  pass "F2 static: verdict-source toggles between arbiter and synthesis"
else
  fail "F2 static: verdict-source toggle missing one of arbiter/synthesis"
fi

# ---------------------------------------------------------------------------
# F2 smoke: with both arbiter and synthesis Verdict sections, arbiter wins.
# ---------------------------------------------------------------------------
F2_DIR="${SCRATCH}/f2-smoke"
mkdir -p "${F2_DIR}/arbiter" "${F2_DIR}/summary"
cat > "${F2_DIR}/summary/final.md" <<'EOF'
## Verdict

SYNTHESIS SAYS: proceed with conditions.
EOF
cat > "${F2_DIR}/arbiter/resolution.md" <<'EOF'
## Verdict

ARBITER RULES: BLOCK pending parity audit.
EOF

# Replay the F1/F2 branch logic in isolation.
_run_output_dir="$F2_DIR"
_synthesis="${_run_output_dir}/summary/final.md"
_arbiter_file="${_run_output_dir}/arbiter/resolution.md"
if [ -f "$_arbiter_file" ]; then
  _verdict_source="$_arbiter_file"
else
  _verdict_source="$_synthesis"
fi
F2_TEXT="$(awk '
  /^## Verdict/ { capture=1; next }
  /^## / && capture { exit }
  capture && NF { out = out (out=="" ? "" : " ") $0 }
  END { print out }
' "$_verdict_source" 2>/dev/null)"
F2_TEXT="$(printf '%s\n' "$F2_TEXT" | sed -E 's/"/\x27/g; s/[[:space:]]+/ /g; s/^ *//; s/ *$//')"

case "$F2_TEXT" in
  "ARBITER RULES:"*)
    pass "F2 smoke: arbiter/resolution.md preferred over summary/final.md"
    ;;
  *)
    fail "F2 smoke: expected arbiter text, got [${F2_TEXT}]"
    ;;
esac

# F2 smoke (inverted): with only summary/final.md, synthesis wins.
F2B_DIR="${SCRATCH}/f2-smoke-fallback"
mkdir -p "${F2B_DIR}/summary"
cat > "${F2B_DIR}/summary/final.md" <<'EOF'
## Verdict

SYNTHESIS ONLY: the gate passes.
EOF
_run_output_dir="$F2B_DIR"
_synthesis="${_run_output_dir}/summary/final.md"
_arbiter_file="${_run_output_dir}/arbiter/resolution.md"
if [ -f "$_arbiter_file" ]; then
  _verdict_source="$_arbiter_file"
else
  _verdict_source="$_synthesis"
fi
F2B_TEXT="$(awk '
  /^## Verdict/ { capture=1; next }
  /^## / && capture { exit }
  capture && NF { out = out (out=="" ? "" : " ") $0 }
  END { print out }
' "$_verdict_source" 2>/dev/null)"
F2B_TEXT="$(printf '%s\n' "$F2B_TEXT" | sed -E 's/"/\x27/g; s/[[:space:]]+/ /g; s/^ *//; s/ *$//')"

case "$F2B_TEXT" in
  "SYNTHESIS ONLY:"*)
    pass "F2 smoke fallback: synthesis used when arbiter absent"
    ;;
  *)
    fail "F2 smoke fallback: expected synthesis text, got [${F2B_TEXT}]"
    ;;
esac

# ---------------------------------------------------------------------------
# F3 static: auto-preflight block present with correct gates.
# ---------------------------------------------------------------------------
if grep -qE '\[ -z "\$\{CONVERSUS_PROVIDER\+set\}" \]' "$ADAPTER"; then
  pass "F3 static: CONVERSUS_PROVIDER unset test (+set) present"
else
  fail "F3 static: CONVERSUS_PROVIDER+set test missing"
fi

if grep -qE '\[ -z "\$\{ANTHROPIC_API_KEY:-\}" \]' "$ADAPTER"; then
  pass "F3 static: ANTHROPIC_API_KEY empty test present"
else
  fail "F3 static: ANTHROPIC_API_KEY empty test missing"
fi

if grep -qE '\$HOME/\.conversus/auth\.json' "$ADAPTER"; then
  pass "F3 static: ~/.conversus/auth.json probe path present"
else
  fail "F3 static: ~/.conversus/auth.json probe path missing"
fi

if grep -qE 'grep -qE .*"\(access_token\|oauth\|subscription\)"' "$ADAPTER"; then
  pass "F3 static: OAuth-marker grep alternation present"
else
  fail "F3 static: OAuth-marker grep alternation missing"
fi

if grep -qE 'CONVERSUS_PROVIDER=claude-code' "$ADAPTER"; then
  pass "F3 static: claude-code assignment present"
else
  fail "F3 static: claude-code assignment missing"
fi

if grep -qE 'echo "note: detected Anthropic OAuth' "$ADAPTER"; then
  pass "F3 static: stderr note: line present"
else
  fail "F3 static: stderr note: line missing"
fi

# Verify the note: line goes to stderr (>&2 on the same line).
if grep -E 'echo "note: detected Anthropic OAuth' "$ADAPTER" | grep -q '>&2'; then
  pass "F3 static: note: line routed to stderr"
else
  fail "F3 static: note: line not routed to stderr"
fi

# ---------------------------------------------------------------------------
# F3 smoke: replay detection heuristic in isolation.
# ---------------------------------------------------------------------------
F3_HOME="${SCRATCH}/f3-home"
mkdir -p "${F3_HOME}/.conversus"
cat > "${F3_HOME}/.conversus/auth.json" <<'EOF'
{
  "anthropic": {
    "access_token": "sk-ant-oat01-FAKE",
    "refresh_token": "fake",
    "expires_at": 9999999999,
    "token_type": "bearer"
  }
}
EOF

# Pure replay: unset CONVERSUS_PROVIDER, unset ANTHROPIC_API_KEY, auth.json present
# with access_token → detection must trigger.
(
  unset CONVERSUS_PROVIDER
  unset ANTHROPIC_API_KEY
  HOME="$F3_HOME"
  if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
    if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
      exit 42
    fi
  fi
  exit 0
)
rc=$?
if [ "$rc" -eq 42 ]; then
  pass "F3 smoke: OAuth marker detected (detection fires)"
else
  fail "F3 smoke: detection failed to fire (rc=$rc)"
fi

# Operator override: CONVERSUS_PROVIDER=anthropic → detection must NOT fire.
(
  CONVERSUS_PROVIDER=anthropic
  export CONVERSUS_PROVIDER
  unset ANTHROPIC_API_KEY
  HOME="$F3_HOME"
  if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
    if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
      exit 42
    fi
  fi
  exit 0
)
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "F3 smoke: explicit CONVERSUS_PROVIDER=anthropic suppresses preflight"
else
  fail "F3 smoke: operator override not respected (rc=$rc)"
fi

# Operator override, explicit empty string: still suppresses (+set is true).
(
  CONVERSUS_PROVIDER=""
  export CONVERSUS_PROVIDER
  unset ANTHROPIC_API_KEY
  HOME="$F3_HOME"
  if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
    if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
      exit 42
    fi
  fi
  exit 0
)
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "F3 smoke: explicit empty CONVERSUS_PROVIDER suppresses preflight"
else
  fail "F3 smoke: +set semantics broken for empty-string (rc=$rc)"
fi

# ANTHROPIC_API_KEY exported → suppresses preflight.
(
  unset CONVERSUS_PROVIDER
  ANTHROPIC_API_KEY=fake
  export ANTHROPIC_API_KEY
  HOME="$F3_HOME"
  if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
    if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
      exit 42
    fi
  fi
  exit 0
)
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "F3 smoke: ANTHROPIC_API_KEY exported suppresses preflight"
else
  fail "F3 smoke: API-key suppression broken (rc=$rc)"
fi

# Missing auth.json → no-op (graceful degradation).
F3_EMPTY_HOME="${SCRATCH}/f3-empty-home"
mkdir -p "${F3_EMPTY_HOME}/.conversus"
(
  unset CONVERSUS_PROVIDER
  unset ANTHROPIC_API_KEY
  HOME="$F3_EMPTY_HOME"
  if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
    if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
      exit 42
    fi
  fi
  exit 0
)
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "F3 smoke: missing auth.json → no-op (graceful degradation)"
else
  fail "F3 smoke: missing auth.json not handled (rc=$rc)"
fi

# Malformed auth.json → no-op (no crash).
F3_MAL_HOME="${SCRATCH}/f3-malformed-home"
mkdir -p "${F3_MAL_HOME}/.conversus"
printf '{ not json ' > "${F3_MAL_HOME}/.conversus/auth.json"
(
  unset CONVERSUS_PROVIDER
  unset ANTHROPIC_API_KEY
  HOME="$F3_MAL_HOME"
  if [ -z "${CONVERSUS_PROVIDER+set}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.conversus/auth.json" ]; then
    if grep -qE '"(access_token|oauth|subscription)"' "$HOME/.conversus/auth.json" 2>/dev/null; then
      exit 42
    fi
  fi
  exit 0
)
rc=$?
# Malformed-but-missing-OAuth-markers → grep returns 1 → detection skipped.
if [ "$rc" -eq 0 ]; then
  pass "F3 smoke: malformed auth.json without OAuth markers → no-op"
else
  fail "F3 smoke: malformed auth.json caused unexpected fire (rc=$rc)"
fi

# ---------------------------------------------------------------------------
# Header comment update — verify the auto-preflight is documented.
# ---------------------------------------------------------------------------
if grep -qE '# .*auto-preflight|# .*T04 auto-preflight|# .*M026/P02/T04 auto-preflight' "$ADAPTER"; then
  pass "header comment documents F3 auto-preflight"
else
  fail "header comment does not document F3 auto-preflight"
fi

# ---------------------------------------------------------------------------
# Bash 3.2 discipline on the adapter changes (no process sub, no mapfile).
# ---------------------------------------------------------------------------
if grep -v -E '^[[:space:]]*#' "$ADAPTER" | grep -nE '<\(|>\(' >/dev/null 2>&1; then
  fail "process substitution introduced"
else
  pass "no process substitution in adapter"
fi
if grep -v -E '^[[:space:]]*#' "$ADAPTER" | grep -nE '\b(mapfile|readarray)\b' >/dev/null 2>&1; then
  fail "mapfile/readarray introduced"
else
  pass "no mapfile/readarray in adapter"
fi

echo "SUMMARY: m026-p02-gate-verdict-reliability.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-gate-verdict-reliability.sh"
  exit 0
fi
echo "FAIL: m026-p02-gate-verdict-reliability.sh" >&2
exit 1
