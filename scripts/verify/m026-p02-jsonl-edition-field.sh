#!/usr/bin/env bash
# scripts/verify/m026-p02-jsonl-edition-field.sh
#
# M026/P02/T02 gate (FR-4, AD-4): verify both conversus_gate_invocation
# JSONL emission sites carry an "edition" field immediately adjacent to
# "adapter_version", with value ∈ {oss, paid, unknown}, never empty,
# never missing. Pre-existing field keys must not be renamed.
#
# Emission sites covered:
#   1. scripts/integrations/github-common.sh::emit_conversus_gate_record
#      — 6th positional `edition` (default "unknown"); emits
#        adapter_version + edition as adjacent `emit_tier1_record` args.
#   2. scripts/specify/specify.sh (inline REC_G literal around line 533)
#      — injects "edition":"${EDITION}" immediately after
#        "adapter_version":"m011-p07".
#
# The script performs:
#   A. Static source-shape grep checks on both files.
#   B. A live stub-mode emission through emit_conversus_gate_record,
#      inspecting the resulting JSONL line for adjacency + value range.
#   C. A field-preservation check (pre-existing keys still present).
#
# Bash 3.2 compatible. AD-19 single-script shape. No process substitution,
# no declare -A, no mapfile/readarray, no subshell pipes in $(...).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMMON="${REPO_ROOT}/scripts/integrations/github-common.sh"
SPECIFY="${REPO_ROOT}/scripts/specify/specify.sh"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1" >&2; failed=$((failed + 1)); }

for f in "$COMMON" "$SPECIFY" "$ADAPTER"; do
  if [ ! -f "$f" ]; then
    fail "required file missing: $f"
    echo "FAIL: m026-p02-jsonl-edition-field.sh" >&2
    exit 1
  fi
done

SCRATCH="$(mktemp -d -t m026-p02-jsonl.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# -----------------------------------------------------------------------
# A. Static source-shape checks: github-common.sh
# -----------------------------------------------------------------------

# A1. emit_conversus_gate_record accepts a 6th positional `edition`
# argument (default unknown).
if grep -qE 'local edition="\$\{6:-unknown\}"' "$COMMON"; then
  pass "github-common.sh: emit_conversus_gate_record has 'local edition=\${6:-unknown}'"
else
  fail "github-common.sh: missing 'local edition=\${6:-unknown}' (backward-compat default)"
fi

# A2. adapter_version + edition emitted adjacently through emit_tier1_record.
# Anchor: the pair of consecutive lines "adapter_version=..." then
# "edition=${edition}" inside the function body.
if grep -qE '"adapter_version=' "$COMMON" && grep -qE '"edition=\$\{edition\}"' "$COMMON"; then
  pass "github-common.sh: adapter_version + edition tokens both present"
else
  fail "github-common.sh: adapter_version or edition token missing from emit_tier1_record args"
fi

# A3. Assert adjacency: the "edition=" arg line directly follows the
# "adapter_version=" arg line. awk over the file to find the line
# numbers; no pipes inside $(...).
ADJ_RESULT="${SCRATCH}/github-common-adjacency.txt"
awk '
  /"adapter_version=/ && ! av_seen { av_line = NR; av_seen = 1 }
  /"edition=\$\{edition\}"/ && ! ed_seen { ed_line = NR; ed_seen = 1 }
  END {
    if (av_seen && ed_seen) {
      print av_line " " ed_line
    } else {
      print "MISSING"
    }
  }
' "$COMMON" > "$ADJ_RESULT"
ADJ_LINE="$(head -n 1 "$ADJ_RESULT")"
case "$ADJ_LINE" in
  MISSING)
    fail "github-common.sh: adapter_version or edition arg not found for adjacency check"
    ;;
  *)
    av_num="${ADJ_LINE%% *}"
    ed_num="${ADJ_LINE##* }"
    delta=$(( ed_num - av_num ))
    if [ "$delta" -eq 1 ]; then
      pass "github-common.sh: edition arg immediately follows adapter_version arg (AD-4 adjacency)"
    else
      fail "github-common.sh: edition arg not adjacent to adapter_version (delta=${delta})"
    fi
    ;;
esac

# A4. Pre-existing field tokens preserved (no silent renames).
for tok in 'issue_ref=\$\{ref\}' 'timeout_sec=\$\{to\}' 'verdict=\$\{verdict\}' 'rc=\$\{rc\}' 'duration_ms=\$\{dur\}'; do
  if grep -qE "\"${tok}\"" "$COMMON"; then
    pass "github-common.sh: preserved pre-existing token ${tok}"
  else
    fail "github-common.sh: pre-existing token ${tok} missing (silent rename?)"
  fi
done

# -----------------------------------------------------------------------
# B. Static source-shape checks: specify.sh
# -----------------------------------------------------------------------

# B1. EDITION= capture line exists and uses the adapter's `check` stdout.
# The adapter path may be spelled directly ("conversus.sh") or through
# an already-resolved variable like $ADAPTER; accept either.
if grep -qE 'EDITION=.*(conversus\.sh|\$ADAPTER).*check' "$SPECIFY"; then
  pass "specify.sh: EDITION= capture invokes conversus adapter check"
else
  fail "specify.sh: EDITION= capture not found or does not invoke conversus adapter check"
fi

# B2. EDITION default to "unknown" when adapter output missing.
if grep -qE ': "\$\{EDITION:=unknown\}"' "$SPECIFY"; then
  pass "specify.sh: EDITION defaults to 'unknown' when adapter output missing"
else
  fail "specify.sh: EDITION default-to-unknown fallback missing"
fi

# B3. REC_G literal carries "edition":"${EDITION}" immediately after
# "adapter_version":"m011-p07". Check the exact ordered substring.
if grep -qE '\\"adapter_version\\":\\"m011-p07\\",\\"edition\\":\\"\$\{EDITION\}\\"' "$SPECIFY"; then
  pass "specify.sh: REC_G places edition immediately after adapter_version (AD-4 adjacency)"
else
  fail "specify.sh: REC_G adjacency of adapter_version+edition not found"
fi

# B4. Pre-existing REC_G keys preserved.
for key in 'type' 'ts' 'gate_id' 'spec_path' 'verdict' 'adapter_version' 'llm_calls' 'elapsed_ms' 'estimated_cost_usd' 'source'; do
  if grep -qE "\\\\\"${key}\\\\\":" "$SPECIFY"; then
    pass "specify.sh: preserved pre-existing REC_G key '${key}'"
  else
    fail "specify.sh: pre-existing REC_G key '${key}' missing (silent rename?)"
  fi
done

# -----------------------------------------------------------------------
# C. Live emission through emit_conversus_gate_record: inspect the
#    emitted JSONL line for adjacency and value range.
# -----------------------------------------------------------------------

EMIT_ROOT="${SCRATCH}/emit-root"
mkdir -p "$EMIT_ROOT"
EMIT_LOG="${EMIT_ROOT}/execution-log.jsonl"

# Drive the emitter with edition=oss (explicit 6th arg).
EMIT_SCRIPT="${SCRATCH}/emit-with-edition.sh"
cat > "$EMIT_SCRIPT" <<'SH'
#!/usr/bin/env bash
set -u
# shellcheck source=/dev/null
. "$1"
ORCHESTRATOR_ROOT="$2" emit_conversus_gate_record "owner/repo#42" "30" "PASS" "0" "1234" "oss"
SH
chmod +x "$EMIT_SCRIPT"
bash "$EMIT_SCRIPT" "$COMMON" "$EMIT_ROOT" >/dev/null 2>&1 || true

if [ -s "$EMIT_LOG" ]; then
  pass "live emit: JSONL record written"
else
  fail "live emit: no JSONL record written to ${EMIT_LOG}"
fi

EMIT_LINE="$(head -n 1 "$EMIT_LOG" 2>/dev/null)"

# C1. edition field present with value oss.
case "$EMIT_LINE" in
  *'"edition":"oss"'*) pass "live emit (edition=oss): edition field present with correct value" ;;
  *) fail "live emit (edition=oss): edition field missing or wrong value (line=${EMIT_LINE})" ;;
esac

# C2. Adjacency: "adapter_version":"..." immediately followed by
# "edition":"...". Use case-glob to assert substring ordering.
case "$EMIT_LINE" in
  *'"adapter_version":"m013-p04","edition":"oss"'*)
    pass "live emit (edition=oss): edition immediately follows adapter_version (AD-4)"
    ;;
  *)
    fail "live emit (edition=oss): adapter_version+edition adjacency broken (line=${EMIT_LINE})"
    ;;
esac

# C3. event type + source still correct (existing readers unaffected).
case "$EMIT_LINE" in
  *'"event":"conversus_gate_invocation"'*) pass "live emit: event=conversus_gate_invocation preserved" ;;
  *) fail "live emit: event type changed (M019 Tier 1 reader would break)" ;;
esac
case "$EMIT_LINE" in
  *'"source":"runtime"'*) pass "live emit: source=runtime preserved" ;;
  *) fail "live emit: source field changed" ;;
esac

# C4. Default-unknown path: omit 6th arg, expect edition=unknown.
DEFAULT_ROOT="${SCRATCH}/default-root"
mkdir -p "$DEFAULT_ROOT"
DEFAULT_LOG="${DEFAULT_ROOT}/execution-log.jsonl"
DEFAULT_SCRIPT="${SCRATCH}/emit-default.sh"
cat > "$DEFAULT_SCRIPT" <<'SH'
#!/usr/bin/env bash
set -u
# shellcheck source=/dev/null
. "$1"
ORCHESTRATOR_ROOT="$2" emit_conversus_gate_record "owner/repo#7" "30" "PASS" "0" "99"
SH
chmod +x "$DEFAULT_SCRIPT"
bash "$DEFAULT_SCRIPT" "$COMMON" "$DEFAULT_ROOT" >/dev/null 2>&1 || true
DEFAULT_LINE="$(head -n 1 "$DEFAULT_LOG" 2>/dev/null)"
case "$DEFAULT_LINE" in
  *'"edition":"unknown"'*)
    pass "live emit (no edition arg): defaults to edition=unknown (backward compat)"
    ;;
  *)
    fail "live emit (no edition arg): did not default to unknown (line=${DEFAULT_LINE})"
    ;;
esac
case "$DEFAULT_LINE" in
  *'"edition":""'*)
    fail "live emit (no edition arg): edition field emitted as empty string (violates never-empty)"
    ;;
  *) : ;;
esac

# C5. Value range: edition ∈ {oss, paid, unknown}. Drive paid branch.
PAID_ROOT="${SCRATCH}/paid-root"
mkdir -p "$PAID_ROOT"
PAID_LOG="${PAID_ROOT}/execution-log.jsonl"
PAID_SCRIPT="${SCRATCH}/emit-paid.sh"
cat > "$PAID_SCRIPT" <<'SH'
#!/usr/bin/env bash
set -u
# shellcheck source=/dev/null
. "$1"
ORCHESTRATOR_ROOT="$2" emit_conversus_gate_record "owner/repo#9" "30" "PASS" "0" "55" "paid"
SH
chmod +x "$PAID_SCRIPT"
bash "$PAID_SCRIPT" "$COMMON" "$PAID_ROOT" >/dev/null 2>&1 || true
PAID_LINE="$(head -n 1 "$PAID_LOG" 2>/dev/null)"
case "$PAID_LINE" in
  *'"edition":"paid"'*) pass "live emit (edition=paid): edition=paid emitted" ;;
  *) fail "live emit (edition=paid): edition=paid missing (line=${PAID_LINE})" ;;
esac

# -----------------------------------------------------------------------
# D. specify.sh REC_G: synthesize the JSON line the inline literal
#    produces with stub values, assert shape. We cannot run specify.sh
#    end-to-end here (it has prompt/TTY semantics), so we verify that the
#    static literal matches the expected ordered-substring after shell
#    variable interpolation would occur.
# -----------------------------------------------------------------------
# Extract the REC_G=... line.
RECG_LINE="$(grep -nE '^    REC_G=' "$SPECIFY" | head -n 1)"
if [ -n "$RECG_LINE" ]; then
  pass "specify.sh: REC_G assignment line located"
else
  fail "specify.sh: REC_G assignment line not found"
fi

# Assert the unescaped key ordering inside REC_G: adapter_version
# must precede edition which must precede llm_calls (AD-4 cluster
# pinned between provenance and metrics).
AV_POS="$(printf '%s\n' "$RECG_LINE" | grep -o 'adapter_version' | head -n 1)"
ED_POS="$(printf '%s\n' "$RECG_LINE" | grep -o 'edition' | head -n 1)"
LL_POS="$(printf '%s\n' "$RECG_LINE" | grep -o 'llm_calls' | head -n 1)"
if [ -n "$AV_POS" ] && [ -n "$ED_POS" ] && [ -n "$LL_POS" ]; then
  # awk-based position check: no pipes inside $(...).
  POS_RESULT="${SCRATCH}/recg-positions.txt"
  awk -v line="$RECG_LINE" '
    BEGIN {
      av = index(line, "adapter_version")
      ed = index(line, "\"edition\"")
      ll = index(line, "llm_calls")
      print av " " ed " " ll
    }
  ' /dev/null > "$POS_RESULT"
  POS_LINE="$(head -n 1 "$POS_RESULT")"
  av_idx="${POS_LINE%% *}"
  rest="${POS_LINE#* }"
  ed_idx="${rest%% *}"
  ll_idx="${rest##* }"
  if [ "$av_idx" -gt 0 ] && [ "$ed_idx" -gt "$av_idx" ] && [ "$ll_idx" -gt "$ed_idx" ]; then
    pass "specify.sh REC_G: key order adapter_version < edition < llm_calls (AD-4 cluster)"
  else
    fail "specify.sh REC_G: key ordering broken (av=${av_idx} ed=${ed_idx} ll=${ll_idx})"
  fi
else
  fail "specify.sh REC_G: one of adapter_version/edition/llm_calls tokens missing"
fi

echo "SUMMARY: m026-p02-jsonl-edition-field.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-jsonl-edition-field.sh"
  exit 0
fi
echo "FAIL: m026-p02-jsonl-edition-field.sh" >&2
exit 1
